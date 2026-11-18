import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/coach.dart';
import 'package:formcheck/data/workout_store.dart';
import 'package:formcheck/domain/workout.dart';

void main() {
  test(
    'camera saves are idempotent, persistent, and excluded from manual stats',
    () async {
      final tmp = await Directory.systemTemp.createTemp('formcheck-test-');
      addTearDown(() => tmp.delete(recursive: true));
      final file = File('${tmp.path}/workouts.sqlite');
      var store = WorkoutStore(NativeDatabase(file));
      const reps = [
        RepResult(RepOutcome.passed, null, 93),
        RepResult(RepOutcome.needsCorrection, Cue.squatDepth, 116),
        RepResult(RepOutcome.unassessed, Cue.reframe),
      ];
      await Future.wait([
        store.saveCamera('set-a', 'session-a', Exercise.squat, reps),
        store.saveCamera('set-a', 'session-a', Exercise.squat, reps),
      ]);
      await store.saveManual(Exercise.squat, 12, 15);
      await expectLater(
        store.saveCamera('set-a', 'session-a', Exercise.squat, [
          const RepResult(RepOutcome.passed, null, 94),
          ...reps.skip(1),
        ]),
        throwsStateError,
      );
      expect(
        () => store.saveCamera('invalid', 'session-a', Exercise.squat, const [
          RepResult(RepOutcome.passed, null, 181),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        store.saveCamera('set-a', 'session-b', Exercise.squat, reps),
        throwsStateError,
      );
      await store.close();
      store = WorkoutStore(NativeDatabase(file));
      addTearDown(store.close);
      final records = await store.watch().first;
      expect(records, hasLength(2));
      final camera = records.singleWhere((set) => set.isCamera);
      expect(camera.reps.map((r) => r.bottomAngleDegrees), [93, 116, null]);
      expect(
        [camera.total, camera.passed, camera.assessed, camera.unassessed],
        [3, 1, 2, 1],
      );
      expect(records.singleWhere((set) => !set.isCamera).total, 12);
      expect(await store.recentComparable(camera), isEmpty);
      await store.deleteAll();
      expect(await store.watch().first, isEmpty);
    },
  );

  test('schema 1 history upgrades with unknown angles and historical profiles intact', () async {
    final tmp = await Directory.systemTemp.createTemp('formcheck-upgrade-');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File('${tmp.path}/workouts.sqlite');
    final store = WorkoutStore(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('''
        CREATE TABLE sessions (id TEXT NOT NULL PRIMARY KEY, started_at INTEGER NOT NULL);
        CREATE TABLE workout_sets (id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE, exercise TEXT NOT NULL, completed_at INTEGER NOT NULL, profile TEXT, manual_reps INTEGER, weight_kg REAL, coach_cue TEXT, coach_observation TEXT, coach_source TEXT);
        CREATE TABLE rep_rows (set_id TEXT NOT NULL REFERENCES workout_sets(id) ON DELETE CASCADE, position INTEGER NOT NULL, outcome TEXT NOT NULL, cue TEXT, PRIMARY KEY(set_id, position));
        CREATE INDEX sets_completed ON workout_sets (completed_at DESC);
        CREATE INDEX sets_comparable ON workout_sets (exercise, profile, completed_at DESC);
        INSERT INTO sessions VALUES ('old', 100);
        INSERT INTO workout_sets (id, session_id, exercise, completed_at, profile) VALUES ('camera', 'old', 'squat', 102, 'side-squat-v4');
        INSERT INTO rep_rows VALUES ('camera', 0, 'needsCorrection', 'squatDepth');
        INSERT INTO workout_sets (id, session_id, exercise, completed_at, manual_reps) VALUES ('manual','old','dumbbellRow',101,8);
        PRAGMA user_version = 1;
      ''');
        },
      ),
    );
    final old = await store.watch().first;
    final camera = old.singleWhere((set) => set.isCamera);
    expect(camera.profile, 'side-squat-v4');
    expect(camera.reps.single.cue, Cue.squatDepth);
    expect(camera.reps.single.bottomAngleDegrees, isNull);
    expect(old.singleWhere((set) => !set.isCamera).total, 8);
    final current = await store.saveCamera(
      'new',
      'new-session',
      Exercise.squat,
      const [RepResult(RepOutcome.passed, null, 88)],
    );
    expect(await store.recentComparable(current), isEmpty);
    await store.close();
    final reopened = WorkoutStore(NativeDatabase(file));
    addTearDown(reopened.close);
    final records = await reopened.watch().first;
    expect(records, hasLength(3));
    expect(
      records.singleWhere((s) => s.id == 'new').reps.single.bottomAngleDegrees,
      88,
    );
  });

  test(
    'coach validates evidence and reuses corrected, successful replies',
    () async {
      final store = WorkoutStore(NativeDatabase.memory());
      addTearDown(store.close);
      final set = await store.saveCamera(
        'set',
        'session',
        Exercise.pushUp,
        const [RepResult(RepOutcome.needsCorrection, Cue.bodyLine, 93)],
      );
      var requestCount = 0;
      final coach = SetCoach(
        store,
        generate: (prompt) async {
          requestCount++;
          expect(prompt, contains('"needsCorrection":1'));
          expect(prompt, isNot(contains('session')));
          expect(prompt, isNot(contains('93')));
          return (
            text: requestCount == 1
                ? '{"observation":"unknown","cue":"squatDepth"}'
                : '{"observation":"current","cue":"bodyLine"}',
            source: CoachSource.cloud,
          );
        },
      );
      expect((await coach.review(set)).source, CoachSource.builtIn);
      final first = coach.review(set);
      final second = coach.review(set);
      expect(identical(first, second), isTrue);
      expect((await first).source, CoachSource.cloud);
      expect((await coach.review(set)).cue, Cue.bodyLine);
      expect(requestCount, 2);
    },
  );
}
