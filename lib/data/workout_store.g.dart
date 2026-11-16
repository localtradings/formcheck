// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_store.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final DateTime startedAt;
  const Session({required this.id, required this.startedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(id: Value(id), startedAt: Value(startedAt));
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  Session copyWith({String? id, DateTime? startedAt}) =>
      Session(id: id ?? this.id, startedAt: startedAt ?? this.startedAt);
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Exercise, String> exercise =
      GeneratedColumn<String>(
        'exercise',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Exercise>($WorkoutSetsTable.$converterexercise);
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileMeta = const VerificationMeta(
    'profile',
  );
  @override
  late final GeneratedColumn<String> profile = GeneratedColumn<String>(
    'profile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualRepsMeta = const VerificationMeta(
    'manualReps',
  );
  @override
  late final GeneratedColumn<int> manualReps = GeneratedColumn<int>(
    'manual_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Cue?, String> coachCue =
      GeneratedColumn<String>(
        'coach_cue',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Cue?>($WorkoutSetsTable.$convertercoachCuen);
  static const VerificationMeta _coachObservationMeta = const VerificationMeta(
    'coachObservation',
  );
  @override
  late final GeneratedColumn<String> coachObservation = GeneratedColumn<String>(
    'coach_observation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CoachSource?, String>
  coachSource = GeneratedColumn<String>(
    'coach_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<CoachSource?>($WorkoutSetsTable.$convertercoachSourcen);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exercise,
    completedAt,
    profile,
    manualReps,
    weightKg,
    coachCue,
    coachObservation,
    coachSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('profile')) {
      context.handle(
        _profileMeta,
        profile.isAcceptableOrUnknown(data['profile']!, _profileMeta),
      );
    }
    if (data.containsKey('manual_reps')) {
      context.handle(
        _manualRepsMeta,
        manualReps.isAcceptableOrUnknown(data['manual_reps']!, _manualRepsMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('coach_observation')) {
      context.handle(
        _coachObservationMeta,
        coachObservation.isAcceptableOrUnknown(
          data['coach_observation']!,
          _coachObservationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      exercise: $WorkoutSetsTable.$converterexercise.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercise'],
        )!,
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      profile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile'],
      ),
      manualReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_reps'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      coachCue: $WorkoutSetsTable.$convertercoachCuen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}coach_cue'],
        ),
      ),
      coachObservation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coach_observation'],
      ),
      coachSource: $WorkoutSetsTable.$convertercoachSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}coach_source'],
        ),
      ),
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Exercise, String, String> $converterexercise =
      const EnumNameConverter<Exercise>(Exercise.values);
  static JsonTypeConverter2<Cue, String, String> $convertercoachCue =
      const EnumNameConverter<Cue>(Cue.values);
  static JsonTypeConverter2<Cue?, String?, String?> $convertercoachCuen =
      JsonTypeConverter2.asNullable($convertercoachCue);
  static JsonTypeConverter2<CoachSource, String, String> $convertercoachSource =
      const EnumNameConverter<CoachSource>(CoachSource.values);
  static JsonTypeConverter2<CoachSource?, String?, String?>
  $convertercoachSourcen = JsonTypeConverter2.asNullable($convertercoachSource);
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final String id;
  final String sessionId;
  final Exercise exercise;
  final DateTime completedAt;
  final String? profile;
  final int? manualReps;
  final double? weightKg;
  final Cue? coachCue;
  final String? coachObservation;
  final CoachSource? coachSource;
  const WorkoutSet({
    required this.id,
    required this.sessionId,
    required this.exercise,
    required this.completedAt,
    this.profile,
    this.manualReps,
    this.weightKg,
    this.coachCue,
    this.coachObservation,
    this.coachSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    {
      map['exercise'] = Variable<String>(
        $WorkoutSetsTable.$converterexercise.toSql(exercise),
      );
    }
    map['completed_at'] = Variable<DateTime>(completedAt);
    if (!nullToAbsent || profile != null) {
      map['profile'] = Variable<String>(profile);
    }
    if (!nullToAbsent || manualReps != null) {
      map['manual_reps'] = Variable<int>(manualReps);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || coachCue != null) {
      map['coach_cue'] = Variable<String>(
        $WorkoutSetsTable.$convertercoachCuen.toSql(coachCue),
      );
    }
    if (!nullToAbsent || coachObservation != null) {
      map['coach_observation'] = Variable<String>(coachObservation);
    }
    if (!nullToAbsent || coachSource != null) {
      map['coach_source'] = Variable<String>(
        $WorkoutSetsTable.$convertercoachSourcen.toSql(coachSource),
      );
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exercise: Value(exercise),
      completedAt: Value(completedAt),
      profile: profile == null && nullToAbsent
          ? const Value.absent()
          : Value(profile),
      manualReps: manualReps == null && nullToAbsent
          ? const Value.absent()
          : Value(manualReps),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      coachCue: coachCue == null && nullToAbsent
          ? const Value.absent()
          : Value(coachCue),
      coachObservation: coachObservation == null && nullToAbsent
          ? const Value.absent()
          : Value(coachObservation),
      coachSource: coachSource == null && nullToAbsent
          ? const Value.absent()
          : Value(coachSource),
    );
  }

  factory WorkoutSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      exercise: $WorkoutSetsTable.$converterexercise.fromJson(
        serializer.fromJson<String>(json['exercise']),
      ),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      profile: serializer.fromJson<String?>(json['profile']),
      manualReps: serializer.fromJson<int?>(json['manualReps']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      coachCue: $WorkoutSetsTable.$convertercoachCuen.fromJson(
        serializer.fromJson<String?>(json['coachCue']),
      ),
      coachObservation: serializer.fromJson<String?>(json['coachObservation']),
      coachSource: $WorkoutSetsTable.$convertercoachSourcen.fromJson(
        serializer.fromJson<String?>(json['coachSource']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'exercise': serializer.toJson<String>(
        $WorkoutSetsTable.$converterexercise.toJson(exercise),
      ),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'profile': serializer.toJson<String?>(profile),
      'manualReps': serializer.toJson<int?>(manualReps),
      'weightKg': serializer.toJson<double?>(weightKg),
      'coachCue': serializer.toJson<String?>(
        $WorkoutSetsTable.$convertercoachCuen.toJson(coachCue),
      ),
      'coachObservation': serializer.toJson<String?>(coachObservation),
      'coachSource': serializer.toJson<String?>(
        $WorkoutSetsTable.$convertercoachSourcen.toJson(coachSource),
      ),
    };
  }

  WorkoutSet copyWith({
    String? id,
    String? sessionId,
    Exercise? exercise,
    DateTime? completedAt,
    Value<String?> profile = const Value.absent(),
    Value<int?> manualReps = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<Cue?> coachCue = const Value.absent(),
    Value<String?> coachObservation = const Value.absent(),
    Value<CoachSource?> coachSource = const Value.absent(),
  }) => WorkoutSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exercise: exercise ?? this.exercise,
    completedAt: completedAt ?? this.completedAt,
    profile: profile.present ? profile.value : this.profile,
    manualReps: manualReps.present ? manualReps.value : this.manualReps,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    coachCue: coachCue.present ? coachCue.value : this.coachCue,
    coachObservation: coachObservation.present
        ? coachObservation.value
        : this.coachObservation,
    coachSource: coachSource.present ? coachSource.value : this.coachSource,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exercise: data.exercise.present ? data.exercise.value : this.exercise,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      profile: data.profile.present ? data.profile.value : this.profile,
      manualReps: data.manualReps.present
          ? data.manualReps.value
          : this.manualReps,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      coachCue: data.coachCue.present ? data.coachCue.value : this.coachCue,
      coachObservation: data.coachObservation.present
          ? data.coachObservation.value
          : this.coachObservation,
      coachSource: data.coachSource.present
          ? data.coachSource.value
          : this.coachSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exercise: $exercise, ')
          ..write('completedAt: $completedAt, ')
          ..write('profile: $profile, ')
          ..write('manualReps: $manualReps, ')
          ..write('weightKg: $weightKg, ')
          ..write('coachCue: $coachCue, ')
          ..write('coachObservation: $coachObservation, ')
          ..write('coachSource: $coachSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exercise,
    completedAt,
    profile,
    manualReps,
    weightKg,
    coachCue,
    coachObservation,
    coachSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exercise == this.exercise &&
          other.completedAt == this.completedAt &&
          other.profile == this.profile &&
          other.manualReps == this.manualReps &&
          other.weightKg == this.weightKg &&
          other.coachCue == this.coachCue &&
          other.coachObservation == this.coachObservation &&
          other.coachSource == this.coachSource);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<Exercise> exercise;
  final Value<DateTime> completedAt;
  final Value<String?> profile;
  final Value<int?> manualReps;
  final Value<double?> weightKg;
  final Value<Cue?> coachCue;
  final Value<String?> coachObservation;
  final Value<CoachSource?> coachSource;
  final Value<int> rowid;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exercise = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.profile = const Value.absent(),
    this.manualReps = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.coachCue = const Value.absent(),
    this.coachObservation = const Value.absent(),
    this.coachSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    required String id,
    required String sessionId,
    required Exercise exercise,
    required DateTime completedAt,
    this.profile = const Value.absent(),
    this.manualReps = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.coachCue = const Value.absent(),
    this.coachObservation = const Value.absent(),
    this.coachSource = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       exercise = Value(exercise),
       completedAt = Value(completedAt);
  static Insertable<WorkoutSet> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? exercise,
    Expression<DateTime>? completedAt,
    Expression<String>? profile,
    Expression<int>? manualReps,
    Expression<double>? weightKg,
    Expression<String>? coachCue,
    Expression<String>? coachObservation,
    Expression<String>? coachSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exercise != null) 'exercise': exercise,
      if (completedAt != null) 'completed_at': completedAt,
      if (profile != null) 'profile': profile,
      if (manualReps != null) 'manual_reps': manualReps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (coachCue != null) 'coach_cue': coachCue,
      if (coachObservation != null) 'coach_observation': coachObservation,
      if (coachSource != null) 'coach_source': coachSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<Exercise>? exercise,
    Value<DateTime>? completedAt,
    Value<String?>? profile,
    Value<int?>? manualReps,
    Value<double?>? weightKg,
    Value<Cue?>? coachCue,
    Value<String?>? coachObservation,
    Value<CoachSource?>? coachSource,
    Value<int>? rowid,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exercise: exercise ?? this.exercise,
      completedAt: completedAt ?? this.completedAt,
      profile: profile ?? this.profile,
      manualReps: manualReps ?? this.manualReps,
      weightKg: weightKg ?? this.weightKg,
      coachCue: coachCue ?? this.coachCue,
      coachObservation: coachObservation ?? this.coachObservation,
      coachSource: coachSource ?? this.coachSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (exercise.present) {
      map['exercise'] = Variable<String>(
        $WorkoutSetsTable.$converterexercise.toSql(exercise.value),
      );
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (profile.present) {
      map['profile'] = Variable<String>(profile.value);
    }
    if (manualReps.present) {
      map['manual_reps'] = Variable<int>(manualReps.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (coachCue.present) {
      map['coach_cue'] = Variable<String>(
        $WorkoutSetsTable.$convertercoachCuen.toSql(coachCue.value),
      );
    }
    if (coachObservation.present) {
      map['coach_observation'] = Variable<String>(coachObservation.value);
    }
    if (coachSource.present) {
      map['coach_source'] = Variable<String>(
        $WorkoutSetsTable.$convertercoachSourcen.toSql(coachSource.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exercise: $exercise, ')
          ..write('completedAt: $completedAt, ')
          ..write('profile: $profile, ')
          ..write('manualReps: $manualReps, ')
          ..write('weightKg: $weightKg, ')
          ..write('coachCue: $coachCue, ')
          ..write('coachObservation: $coachObservation, ')
          ..write('coachSource: $coachSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepRowsTable extends RepRows with TableInfo<$RepRowsTable, RepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RepOutcome, String> outcome =
      GeneratedColumn<String>(
        'outcome',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RepOutcome>($RepRowsTable.$converteroutcome);
  @override
  late final GeneratedColumnWithTypeConverter<Cue?, String> cue =
      GeneratedColumn<String>(
        'cue',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Cue?>($RepRowsTable.$convertercuen);
  @override
  List<GeneratedColumn> get $columns => [setId, position, outcome, cue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rep_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setId, position};
  @override
  RepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepRow(
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      outcome: $RepRowsTable.$converteroutcome.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}outcome'],
        )!,
      ),
      cue: $RepRowsTable.$convertercuen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cue'],
        ),
      ),
    );
  }

  @override
  $RepRowsTable createAlias(String alias) {
    return $RepRowsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RepOutcome, String, String> $converteroutcome =
      const EnumNameConverter<RepOutcome>(RepOutcome.values);
  static JsonTypeConverter2<Cue, String, String> $convertercue =
      const EnumNameConverter<Cue>(Cue.values);
  static JsonTypeConverter2<Cue?, String?, String?> $convertercuen =
      JsonTypeConverter2.asNullable($convertercue);
}

class RepRow extends DataClass implements Insertable<RepRow> {
  final String setId;
  final int position;
  final RepOutcome outcome;
  final Cue? cue;
  const RepRow({
    required this.setId,
    required this.position,
    required this.outcome,
    this.cue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['set_id'] = Variable<String>(setId);
    map['position'] = Variable<int>(position);
    {
      map['outcome'] = Variable<String>(
        $RepRowsTable.$converteroutcome.toSql(outcome),
      );
    }
    if (!nullToAbsent || cue != null) {
      map['cue'] = Variable<String>($RepRowsTable.$convertercuen.toSql(cue));
    }
    return map;
  }

  RepRowsCompanion toCompanion(bool nullToAbsent) {
    return RepRowsCompanion(
      setId: Value(setId),
      position: Value(position),
      outcome: Value(outcome),
      cue: cue == null && nullToAbsent ? const Value.absent() : Value(cue),
    );
  }

  factory RepRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepRow(
      setId: serializer.fromJson<String>(json['setId']),
      position: serializer.fromJson<int>(json['position']),
      outcome: $RepRowsTable.$converteroutcome.fromJson(
        serializer.fromJson<String>(json['outcome']),
      ),
      cue: $RepRowsTable.$convertercuen.fromJson(
        serializer.fromJson<String?>(json['cue']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setId': serializer.toJson<String>(setId),
      'position': serializer.toJson<int>(position),
      'outcome': serializer.toJson<String>(
        $RepRowsTable.$converteroutcome.toJson(outcome),
      ),
      'cue': serializer.toJson<String?>(
        $RepRowsTable.$convertercuen.toJson(cue),
      ),
    };
  }

  RepRow copyWith({
    String? setId,
    int? position,
    RepOutcome? outcome,
    Value<Cue?> cue = const Value.absent(),
  }) => RepRow(
    setId: setId ?? this.setId,
    position: position ?? this.position,
    outcome: outcome ?? this.outcome,
    cue: cue.present ? cue.value : this.cue,
  );
  RepRow copyWithCompanion(RepRowsCompanion data) {
    return RepRow(
      setId: data.setId.present ? data.setId.value : this.setId,
      position: data.position.present ? data.position.value : this.position,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      cue: data.cue.present ? data.cue.value : this.cue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepRow(')
          ..write('setId: $setId, ')
          ..write('position: $position, ')
          ..write('outcome: $outcome, ')
          ..write('cue: $cue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(setId, position, outcome, cue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepRow &&
          other.setId == this.setId &&
          other.position == this.position &&
          other.outcome == this.outcome &&
          other.cue == this.cue);
}

class RepRowsCompanion extends UpdateCompanion<RepRow> {
  final Value<String> setId;
  final Value<int> position;
  final Value<RepOutcome> outcome;
  final Value<Cue?> cue;
  final Value<int> rowid;
  const RepRowsCompanion({
    this.setId = const Value.absent(),
    this.position = const Value.absent(),
    this.outcome = const Value.absent(),
    this.cue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepRowsCompanion.insert({
    required String setId,
    required int position,
    required RepOutcome outcome,
    this.cue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : setId = Value(setId),
       position = Value(position),
       outcome = Value(outcome);
  static Insertable<RepRow> custom({
    Expression<String>? setId,
    Expression<int>? position,
    Expression<String>? outcome,
    Expression<String>? cue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (setId != null) 'set_id': setId,
      if (position != null) 'position': position,
      if (outcome != null) 'outcome': outcome,
      if (cue != null) 'cue': cue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepRowsCompanion copyWith({
    Value<String>? setId,
    Value<int>? position,
    Value<RepOutcome>? outcome,
    Value<Cue?>? cue,
    Value<int>? rowid,
  }) {
    return RepRowsCompanion(
      setId: setId ?? this.setId,
      position: position ?? this.position,
      outcome: outcome ?? this.outcome,
      cue: cue ?? this.cue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(
        $RepRowsTable.$converteroutcome.toSql(outcome.value),
      );
    }
    if (cue.present) {
      map['cue'] = Variable<String>(
        $RepRowsTable.$convertercuen.toSql(cue.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepRowsCompanion(')
          ..write('setId: $setId, ')
          ..write('position: $position, ')
          ..write('outcome: $outcome, ')
          ..write('cue: $cue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WorkoutStore extends GeneratedDatabase {
  _$WorkoutStore(QueryExecutor e) : super(e);
  $WorkoutStoreManager get managers => $WorkoutStoreManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $RepRowsTable repRows = $RepRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    workoutSets,
    repRows,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rep_rows', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required DateTime startedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<DateTime> startedAt,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$WorkoutStore, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
  _workoutSetsRefsTable(_$WorkoutStore db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: 'sessions__id__workout_sets__session_id',
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$WorkoutStore, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$WorkoutStore, $SessionsTable> {
  $$SessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$WorkoutStore, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$WorkoutStore,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool workoutSetsRefs})
        > {
  $$SessionsTableTableManager(_$WorkoutStore db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SessionsCompanion(id: id, startedAt: startedAt, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, Session>(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workoutSetsRefs) db.workoutSets],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutSetsRefs)
                    await $_getPrefetchedDataByColumns<
                      Session,
                      $SessionsTable,
                      WorkoutSet,
                      $WorkoutSetsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._workoutSetsRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(
                        db,
                        table,
                        p0,
                      ).workoutSetsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'session_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkoutStore,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool workoutSetsRefs})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder =
    WorkoutSetsCompanion Function({
      required String id,
      required String sessionId,
      required Exercise exercise,
      required DateTime completedAt,
      Value<String?> profile,
      Value<int?> manualReps,
      Value<double?> weightKg,
      Value<Cue?> coachCue,
      Value<String?> coachObservation,
      Value<CoachSource?> coachSource,
      Value<int> rowid,
    });
typedef $$WorkoutSetsTableUpdateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<Exercise> exercise,
      Value<DateTime> completedAt,
      Value<String?> profile,
      Value<int?> manualReps,
      Value<double?> weightKg,
      Value<Cue?> coachCue,
      Value<String?> coachObservation,
      Value<CoachSource?> coachSource,
      Value<int> rowid,
    });

final class $$WorkoutSetsTableReferences
    extends BaseReferences<_$WorkoutStore, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$WorkoutStore db) =>
      db.sessions.createAlias('workout_sets__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RepRowsTable, List<RepRow>> _repRowsRefsTable(
    _$WorkoutStore db,
  ) => MultiTypedResultKey.fromTable(
    db.repRows,
    aliasName: 'workout_sets__id__rep_rows__set_id',
  );

  $$RepRowsTableProcessedTableManager get repRowsRefs {
    final manager = $$RepRowsTableTableManager(
      $_db,
      $_db.repRows,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_repRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$WorkoutStore, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<Exercise, Exercise, String> get exercise =>
      $composableBuilder(
        column: $table.exercise,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualReps => $composableBuilder(
    column: $table.manualReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Cue?, Cue, String> get coachCue =>
      $composableBuilder(
        column: $table.coachCue,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get coachObservation => $composableBuilder(
    column: $table.coachObservation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CoachSource?, CoachSource, String>
  get coachSource => $composableBuilder(
    column: $table.coachSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> repRowsRefs(
    Expression<bool> Function($$RepRowsTableFilterComposer f) f,
  ) {
    final $$RepRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repRows,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepRowsTableFilterComposer(
            $db: $db,
            $table: $db.repRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$WorkoutStore, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
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

  ColumnOrderings<String> get exercise => $composableBuilder(
    column: $table.exercise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualReps => $composableBuilder(
    column: $table.manualReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coachCue => $composableBuilder(
    column: $table.coachCue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coachObservation => $composableBuilder(
    column: $table.coachObservation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coachSource => $composableBuilder(
    column: $table.coachSource,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$WorkoutStore, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Exercise, String> get exercise =>
      $composableBuilder(column: $table.exercise, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profile =>
      $composableBuilder(column: $table.profile, builder: (column) => column);

  GeneratedColumn<int> get manualReps => $composableBuilder(
    column: $table.manualReps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Cue?, String> get coachCue =>
      $composableBuilder(column: $table.coachCue, builder: (column) => column);

  GeneratedColumn<String> get coachObservation => $composableBuilder(
    column: $table.coachObservation,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CoachSource?, String> get coachSource =>
      $composableBuilder(
        column: $table.coachSource,
        builder: (column) => column,
      );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> repRowsRefs<T extends Object>(
    Expression<T> Function($$RepRowsTableAnnotationComposer a) f,
  ) {
    final $$RepRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repRows,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.repRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$WorkoutStore,
          $WorkoutSetsTable,
          WorkoutSet,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSet, $$WorkoutSetsTableReferences),
          WorkoutSet,
          PrefetchHooks Function({bool sessionId, bool repRowsRefs})
        > {
  $$WorkoutSetsTableTableManager(_$WorkoutStore db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<Exercise> exercise = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<String?> profile = const Value.absent(),
                Value<int?> manualReps = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<Cue?> coachCue = const Value.absent(),
                Value<String?> coachObservation = const Value.absent(),
                Value<CoachSource?> coachSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                sessionId: sessionId,
                exercise: exercise,
                completedAt: completedAt,
                profile: profile,
                manualReps: manualReps,
                weightKg: weightKg,
                coachCue: coachCue,
                coachObservation: coachObservation,
                coachSource: coachSource,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required Exercise exercise,
                required DateTime completedAt,
                Value<String?> profile = const Value.absent(),
                Value<int?> manualReps = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<Cue?> coachCue = const Value.absent(),
                Value<String?> coachObservation = const Value.absent(),
                Value<CoachSource?> coachSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                exercise: exercise,
                completedAt: completedAt,
                profile: profile,
                manualReps: manualReps,
                weightKg: weightKg,
                coachCue: coachCue,
                coachObservation: coachObservation,
                coachSource: coachSource,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSetsTable, WorkoutSet>(table),
                  $$WorkoutSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, repRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (repRowsRefs) db.repRows],
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$WorkoutSetsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$WorkoutSetsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (repRowsRefs)
                    await $_getPrefetchedDataByColumns<
                      WorkoutSet,
                      $WorkoutSetsTable,
                      RepRow,
                      $RepRowsTable
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutSetsTableReferences
                          ._repRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).repRowsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'set_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkoutStore,
      $WorkoutSetsTable,
      WorkoutSet,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSet, $$WorkoutSetsTableReferences),
      WorkoutSet,
      PrefetchHooks Function({bool sessionId, bool repRowsRefs})
    >;
typedef $$RepRowsTableCreateCompanionBuilder = RepRowsCompanion Function({
  required String setId,
  required int position,
  required RepOutcome outcome,
  Value<Cue?> cue,
  Value<int> rowid,
});
typedef $$RepRowsTableUpdateCompanionBuilder = RepRowsCompanion Function({
  Value<String> setId,
  Value<int> position,
  Value<RepOutcome> outcome,
  Value<Cue?> cue,
  Value<int> rowid,
});

final class $$RepRowsTableReferences
    extends BaseReferences<_$WorkoutStore, $RepRowsTable, RepRow> {
  $$RepRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutSetsTable _setIdTable(_$WorkoutStore db) =>
      db.workoutSets.createAlias('rep_rows__set_id__workout_sets__id');

  $$WorkoutSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<String>('set_id')!;

    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RepRowsTableFilterComposer
    extends Composer<_$WorkoutStore, $RepRowsTable> {
  $$RepRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RepOutcome, RepOutcome, String> get outcome =>
      $composableBuilder(
        column: $table.outcome,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Cue?, Cue, String> get cue =>
      $composableBuilder(
        column: $table.cue,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$WorkoutSetsTableFilterComposer get setId {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRowsTableOrderingComposer
    extends Composer<_$WorkoutStore, $RepRowsTable> {
  $$RepRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cue => $composableBuilder(
    column: $table.cue,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSetsTableOrderingComposer get setId {
    final $$WorkoutSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRowsTableAnnotationComposer
    extends Composer<_$WorkoutStore, $RepRowsTable> {
  $$RepRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RepOutcome, String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Cue?, String> get cue =>
      $composableBuilder(column: $table.cue, builder: (column) => column);

  $$WorkoutSetsTableAnnotationComposer get setId {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepRowsTableTableManager
    extends
        RootTableManager<
          _$WorkoutStore,
          $RepRowsTable,
          RepRow,
          $$RepRowsTableFilterComposer,
          $$RepRowsTableOrderingComposer,
          $$RepRowsTableAnnotationComposer,
          $$RepRowsTableCreateCompanionBuilder,
          $$RepRowsTableUpdateCompanionBuilder,
          (RepRow, $$RepRowsTableReferences),
          RepRow,
          PrefetchHooks Function({bool setId})
        > {
  $$RepRowsTableTableManager(_$WorkoutStore db, $RepRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> setId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<RepOutcome> outcome = const Value.absent(),
                Value<Cue?> cue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepRowsCompanion(
                setId: setId,
                position: position,
                outcome: outcome,
                cue: cue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String setId,
                required int position,
                required RepOutcome outcome,
                Value<Cue?> cue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepRowsCompanion.insert(
                setId: setId,
                position: position,
                outcome: outcome,
                cue: cue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RepRowsTable, RepRow>(table),
                  $$RepRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
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
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $$RepRowsTableReferences._setIdTable(
                          db,
                        ),
                        referencedColumn: $$RepRowsTableReferences
                            ._setIdTable(db)
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

typedef $$RepRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkoutStore,
      $RepRowsTable,
      RepRow,
      $$RepRowsTableFilterComposer,
      $$RepRowsTableOrderingComposer,
      $$RepRowsTableAnnotationComposer,
      $$RepRowsTableCreateCompanionBuilder,
      $$RepRowsTableUpdateCompanionBuilder,
      (RepRow, $$RepRowsTableReferences),
      RepRow,
      PrefetchHooks Function({bool setId})
    >;

class $WorkoutStoreManager {
  final _$WorkoutStore _db;
  $WorkoutStoreManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$RepRowsTableTableManager get repRows =>
      $$RepRowsTableTableManager(_db, _db.repRows);
}
