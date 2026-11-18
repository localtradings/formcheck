import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/domain/exercise_assessment.dart';
import 'package:formcheck/domain/phone_level.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/domain/workout.dart';

void main() {
  test(
    'setup cues use the visible plank and clear on tilt, loss or correction',
    () {
      final session = ExerciseAssessment(Exercise.pushUp);
      List<Joint> plank(double hipY) {
        final joints = List.filled(33, const Joint(0, 0, 0));
        joints[11] = const Joint(.72, .40, .99);
        joints[13] = const Joint(.72, .51, .99);
        joints[15] = const Joint(.72, .63, .99);
        joints[23] = Joint(.45, hipY, .99);
        joints[25] = Joint(.315, (hipY + .48) / 2, .99);
        joints[27] = const Joint(.18, .48, .99);
        return joints;
      }

      var now = 0;
      void hold(
        List<List<Joint>> people, {
        PhoneLevel? level,
        int frames = 12,
      }) {
        for (var i = 0; i < frames; i++) {
          session.accept(PoseSample(now += 80, 1, people), const [], level);
        }
      }

      hold([plank(.35)]);
      expect(session.setupCue, Cue.bodyLine);
      hold([plank(.35)], level: const PhoneLevel(30, tilted: true), frames: 1);
      expect(session.setupCue, isNull);
      hold([plank(.35)]);
      expect(session.setupCue, Cue.bodyLine);
      hold([], frames: 1);
      expect(session.setupCue, isNull);
      hold([plank(.44)]);
      expect(session.setupCue, isNull);
    },
  );

  test(
    'the lens level works in both orientations and expires stale readings',
    () {
      final sensor = PhoneLevelFilter();
      for (final upright in [
        (0.0, 9.81),
        (0.0, -9.81),
        (9.81, 0.0),
        (-9.81, 0.0),
      ]) {
        sensor.reset();
        expect(sensor.at(0), isNull);
        for (final ms in [0, 100, 200]) {
          sensor.add(ms, upright.$1, upright.$2, 0);
        }
        final level = sensor.at(250)!;
        expect(level.pitchDegrees, closeTo(0, .01));
        expect(level.blocksAssessment, isFalse);
        expect(sensor.at(800), isNull);
      }
      sensor.reset();
      for (final ms in [10, 110, 210]) {
        sensor.add(ms, 0, 9.81 * math.cos(math.pi / 6), -9.81 / 2);
      }
      expect(sensor.at(210)!.pitchDegrees, closeTo(30, .02));
      expect(sensor.at(210)!.tilted, isTrue);
      sensor.add(310, 0, 0, 9.81);
      expect(sensor.at(310)!.pitchDegrees, isNull);
      sensor.add(410, 0, 0, 9.81);
      sensor.add(510, 0, 0, 9.81);
      expect(sensor.at(510)!.pitchDegrees, 90);
      sensor.add(610, double.nan, 0, 0);
      expect(sensor.at(610)!.blocksAssessment, isTrue);
      sensor.add(710, 25, 1, 1);
      expect(sensor.at(710)!.pitchDegrees, isNull);
      // A late callback carrying an earlier sample cannot replace the movement.
      sensor.add(600, 0, 9.81, 0);
      expect(sensor.at(710)!.pitchDegrees, isNull);
    },
  );

  test(
    'a steady rolled phone and a level landscape phone have different advice',
    () {
      final sensor = PhoneLevelFilter();
      for (final ms in [0, 100, 200]) {
        sensor.add(ms, 9.81 / math.sqrt2, -9.81 / math.sqrt2, 0);
      }
      expect(sensor.at(210)!.rolled, isTrue);
      expect(sensor.at(210)!.pitchDegrees, closeTo(0, .01));
      for (final ms in [310, 410, 510]) {
        sensor.add(ms, 9.81, 0, 0);
      }
      expect(sensor.at(510)!.blocksAssessment, isFalse);
    },
  );

  test('camera and phone angle gates discard an interrupted rep and allow a fresh one', () {
    for (final wrongPosition in ['bearing', 'pitch', 'roll', 'moving']) {
      final session = ExerciseAssessment(Exercise.squat);
      final results = <RepResult>[];
      var now = 0;
      Analysis show({bool down = false, bool wrong = false, int frames = 8}) {
        final joints = List.filled(33, const Joint(0, 0, 0));
        void both(int index, double x, double y) {
          joints[index] = Joint(x, y, .99);
          joints[index + 1] = Joint(
            x + (wrong && wrongPosition == 'bearing' ? .19 : .01),
            y,
            .95,
          );
        }

        both(11, down ? .39 : .56, down ? .42 : .24);
        both(23, down ? .37 : .54, down ? .62 : .44);
        both(25, .55, .62);
        both(27, .55, .80);
        final level = wrong
            ? switch (wrongPosition) {
                'pitch' => const PhoneLevel(32, tilted: true),
                'roll' => const PhoneLevel(0, rolled: true),
                'moving' => const PhoneLevel.moving(),
                _ => const PhoneLevel(0),
              }
            : null;
        late Analysis result;
        for (var i = 0; i < frames; i++) {
          result = session.accept(
            PoseSample(now += 80, 1, [joints]),
            const [],
            level,
          );
          if (result.rep != null) results.add(result.rep!);
        }
        return result;
      }

      expect(show().status, TrackingStatus.ready);
      show(down: true);
      show();
      expect(results, hasLength(1));
      show(down: true);
      expect(show(wrong: true).status, TrackingStatus.reposition);
      expect(session.jointAngleDegrees, isNull);
      expect(session.adjustment, isNotNull);
      expect(show(frames: 12).status, TrackingStatus.ready);
      expect(results, hasLength(1), reason: wrongPosition);
      show(down: true);
      show();
      expect(results.map((e) => e.outcome), [
        RepOutcome.passed,
        RepOutcome.passed,
      ]);
      session.reset();
      expect(session.jointAngleDegrees, isNull);
      expect(session.placement.estimatedDegrees, isNull);
      expect(session.level, isNull);
    }
  });
}
