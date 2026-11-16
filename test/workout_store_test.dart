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
        RepResult(RepOutcome.passed),
        RepResult(RepOutcome.needsCorrection, Cue.squatDepth),
        RepResult(RepOutcome.unassessed, Cue.reframe),
      ];
      await Future.wait([
        store.saveCamera('set-a', 'session-a', Exercise.squat, reps),
        store.saveCamera('set-a', 'session-a', Exercise.squat, reps),
      ]);
      await store.saveManual(Exercise.squat, 12, 15);
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

  test(
    'coach validates evidence and reuses corrected, successful replies',
    () async {
      final store = WorkoutStore(NativeDatabase.memory());
      addTearDown(store.close);
      final set = await store.saveCamera(
        'set',
        'session',
        Exercise.pushUp,
        const [RepResult(RepOutcome.needsCorrection, Cue.bodyLine)],
      );
      var requestCount = 0;
      final coach = SetCoach(
        store,
        generate: (prompt) async {
          requestCount++;
          expect(prompt, contains('"needsCorrection":1'));
          expect(prompt, isNot(contains('session')));
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
