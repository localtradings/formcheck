import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';

part 'workout_store.g.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exercise => textEnum<Exercise>()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get profile => text().nullable()();
  IntColumn get manualReps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get coachCue => textEnum<Cue>().nullable()();
  TextColumn get coachObservation => text().nullable()();
  TextColumn get coachSource => textEnum<CoachSource>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RepRows extends Table {
  TextColumn get setId =>
      text().references(WorkoutSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get outcome => textEnum<RepOutcome>()();
  TextColumn get cue => textEnum<Cue>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {setId, position};
}

@DriftDatabase(tables: [Sessions, WorkoutSets, RepRows])
class WorkoutStore extends _$WorkoutStore {
  WorkoutStore([QueryExecutor? executor]) : super(executor ?? _connect());

  static QueryExecutor _connect() => LazyDatabase(() async {
    final support = await getApplicationSupportDirectory();
    final directory = await Directory(path.join(support.path, 'workouts'))
        .create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel('formcheck/device')
          .invokeMethod<void>('excludeBackup', directory.path);
    }
    return NativeDatabase.createInBackground(
      File(path.join(directory.path, 'formcheck.sqlite')),
    );
  });

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX sets_completed ON workout_sets (completed_at DESC)',
      );
      await customStatement(
        'CREATE INDEX sets_comparable ON workout_sets (exercise, profile, completed_at DESC)',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA secure_delete = ON');
    },
  );

  Stream<List<SetRecord>> watch() => _joined(
    (selectOnly(workoutSets)..addColumns([workoutSets.id]))
      ..orderBy([
        OrderingTerm.desc(workoutSets.completedAt),
        OrderingTerm.desc(workoutSets.id),
      ])
      ..limit(200),
  ).watch().map(_records);

  Future<List<SetRecord>> recentComparable(SetRecord record) async {
    if (!record.isCamera || record.profile == null) return [];
    final query = selectOnly(workoutSets)
      ..addColumns([workoutSets.id])
      ..where(
        workoutSets.exercise.equalsValue(record.exercise) &
            workoutSets.profile.equals(record.profile!) &
            workoutSets.completedAt.isSmallerOrEqualValue(record.at) &
            workoutSets.id.equals(record.id).not(),
      )
      ..orderBy([OrderingTerm.desc(workoutSets.completedAt)])
      ..limit(3);
    return _records(await _joined(query).get());
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joined(
    BaseSelectStatement sets,
  ) =>
      select(workoutSets).join([
          leftOuterJoin(repRows, repRows.setId.equalsExp(workoutSets.id)),
        ])
        ..where(workoutSets.id.isInQuery(sets))
        ..orderBy([
          OrderingTerm.desc(workoutSets.completedAt),
          OrderingTerm.desc(workoutSets.id),
          OrderingTerm.asc(repRows.position),
        ]);

  List<SetRecord> _records(List<TypedResult> rows) {
    final records = <String, (WorkoutSet, List<RepResult>)>{};
    for (final row in rows) {
      final set = row.readTable(workoutSets);
      final group = records.putIfAbsent(set.id, () => (set, []));
      final rep = row.readTableOrNull(repRows);
      if (rep != null) group.$2.add(RepResult(rep.outcome, rep.cue));
    }
    return [
      for (final (set, reps) in records.values)
        SetRecord(
          id: set.id,
          sessionId: set.sessionId,
          exercise: set.exercise,
          at: set.completedAt,
          reps: reps,
          manualReps: set.manualReps,
          weightKg: set.weightKg,
          profile: set.profile,
        ),
    ];
  }

  Future<SetRecord> saveCamera(
    String id,
    String sessionId,
    Exercise exercise,
    List<RepResult> reps,
  ) {
    if (!exercise.cameraSupported || reps.isEmpty || reps.length > 999) {
      throw ArgumentError('Invalid camera set');
    }
    return _save(
      SetRecord(
        id: id,
        sessionId: sessionId,
        exercise: exercise,
        at: DateTime.now(),
        reps: reps,
        profile: FormProfile.forExercise(exercise).id,
      ),
    );
  }

  Future<SetRecord> saveManual(Exercise exercise, int reps, double? weightKg) {
    if (reps < 1 ||
        reps > 999 ||
        (weightKg != null &&
            (!weightKg.isFinite || weightKg < 0 || weightKg > 1000))) {
      throw ArgumentError('Enter 1–999 reps and a weight from 0 to 1,000 kg.');
    }
    final id = const Uuid().v4();
    return _save(
      SetRecord(
        id: id,
        sessionId: id,
        exercise: exercise,
        at: DateTime.now(),
        manualReps: reps,
        weightKg: weightKg,
      ),
    );
  }

  Future<SetRecord> _save(SetRecord record) => transaction(() async {
    final existing = await (select(
      workoutSets,
    )..where((row) => row.id.equals(record.id))).getSingleOrNull();
    if (existing != null) {
      final priorReps =
          await (select(repRows)
                ..where((rep) => rep.setId.equals(record.id))
                ..orderBy([(rep) => OrderingTerm.asc(rep.position)]))
              .get();
      if (existing.sessionId != record.sessionId ||
          existing.exercise != record.exercise ||
          existing.profile != record.profile ||
          priorReps.length != record.reps.length ||
          !List.generate(
            priorReps.length,
            (index) =>
                priorReps[index].outcome == record.reps[index].outcome &&
                priorReps[index].cue == record.reps[index].cue,
          ).every((match) => match)) {
        throw StateError('Set ID already used with different results.');
      }
      return SetRecord(
        id: existing.id,
        sessionId: existing.sessionId,
        exercise: existing.exercise,
        at: existing.completedAt,
        reps: record.reps,
        profile: existing.profile,
      );
    }
    await into(sessions).insert(
      SessionsCompanion.insert(id: record.sessionId, startedAt: record.at),
      mode: InsertMode.insertOrIgnore,
    );
    await into(workoutSets).insert(
      WorkoutSetsCompanion.insert(
        id: record.id,
        sessionId: record.sessionId,
        exercise: record.exercise,
        completedAt: record.at,
        profile: Value(record.profile),
        manualReps: Value(record.manualReps),
        weightKg: Value(record.weightKg),
      ),
    );
    await batch(
      (batch) => batch.insertAll(repRows, [
        for (final (index, rep) in record.reps.indexed)
          RepRowsCompanion.insert(
            setId: record.id,
            position: index,
            outcome: rep.outcome,
            cue: Value(rep.cue),
          ),
      ]),
    );
    return record;
  });

  Future<CoachAdvice?> cachedAdvice(String setId) async {
    final row = await (select(
      workoutSets,
    )..where((set) => set.id.equals(setId))).getSingleOrNull();
    if (row?.coachSource == null) return null;
    return CoachAdvice(row!.coachCue!, row.coachObservation!, row.coachSource!);
  }

  Future<void> saveAdvice(String setId, CoachAdvice advice) async {
    await (update(workoutSets)..where((row) => row.id.equals(setId))).write(
      WorkoutSetsCompanion(
        coachCue: Value(advice.cue),
        coachObservation: Value(advice.observation),
        coachSource: Value(advice.source),
      ),
    );
  }

  Future<void> deleteAll() async {
    await delete(sessions).go();
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }
}
