import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/domain/camera_placement.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/domain/workout.dart';

typedef _Body = ({List<Joint> image, List<WorldJoint> world});

_Body _body(
  Exercise exercise,
  double bearing, {
  double? hipsBearing,
  double aspect = 1,
  bool mirrored = false,
  bool farSideVisible = true,
}) {
  final image = List.filled(33, const Joint(0, 0, 0));
  final world = List.filled(33, const WorldJoint(0, 0, 0));
  final squat = exercise == Exercise.squat;
  void pair(int index, double x, double y, double width, double angle) {
    final radians = angle * math.pi / 180;
    for (var side = 0; side < 2; side++) {
      final offset = side == 0 ? -.5 : .5;
      final lateral = offset * width * math.cos(radians);
      final depth = offset * width * math.sin(radians);
      final confidence = side == 1 && !farSideVisible ? .2 : .98;
      final screenX = .5 + (x + lateral) * .54 / aspect;
      image[index + side] = Joint(
        mirrored ? 1 - screenX : screenX,
        .5 + y * .54,
        confidence,
      );
      world[index + side] = WorldJoint(
        mirrored ? -x - lateral : x + lateral,
        y,
        depth,
        confidence,
      );
    }
  }

  final lengthInView = math.sin(bearing.abs() * math.pi / 180);
  pair(11, squat ? 0 : .46 * lengthInView, squat ? -.50 : -.09, .40, bearing);
  pair(23, 0, 0, .26, hipsBearing ?? bearing);
  pair(25, squat ? .03 : -.22 * lengthInView, squat ? .30 : .03, .20, bearing);
  pair(27, squat ? 0 : -.50 * lengthInView, squat ? .64 : .08, .20, bearing);
  pair(13, squat ? .01 : .48 * lengthInView, squat ? -.23 : .10, .34, bearing);
  pair(15, squat ? .02 : .50 * lengthInView, squat ? .02 : .26, .34, bearing);
  return (image: image, world: world);
}

class _Replay {
  _Replay(Exercise exercise, {this.aspect = 1})
    : placement = CameraPlacement(exercise);
  final CameraPlacement placement;
  final double aspect;
  int time = 0;

  PlacementReading show(
    _Body body, {
    int frames = 1,
    bool useWorld = true,
    int step = 80,
  }) {
    var last = const PlacementReading.unknown();
    for (var index = 0; index < frames; index++) {
      time += step;
      last = placement.update(
        PoseSample(time, aspect, [body.image]),
        useWorld ? body.world : const [],
      );
    }
    return last;
  }
}

void main() {
  test('tracks either side of both exercises across aspect and display reflections', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      for (final aspect in [.7, 1.65]) {
        for (final mirrored in [false, true]) {
          for (final angle in [-82.0, 82.0]) {
            final replay = _Replay(exercise, aspect: aspect);
            final shape = _body(
              exercise,
              angle,
              aspect: aspect,
              mirrored: mirrored,
            );
            final first = replay.show(shape);
            expect(first.estimatedDegrees, isNull);
            final settled = replay.show(shape, frames: 7);
            expect(settled.view, PlacementView.side);
            expect(settled.estimatedDegrees, 80);
            expect(settled.blockAssessment, isFalse);
          }
        }
      }
    }
  });

  test('clearly frontal, rear-equivalent and oblique views stop assessment for both exercises', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      for (final angle in [0.0, 10.0, 45.0, -55.0, 140.0, 180.0]) {
        final replay = _Replay(exercise);
        final body = _body(exercise, angle);
        expect(replay.show(body).blockAssessment, isTrue);
        final reading = replay.show(body, frames: 8);
        expect(reading.view, PlacementView.moveToSide);
        final acute = math.min(angle.abs(), 180 - angle.abs());
        expect(reading.estimatedDegrees, (acute / 5).round() * 5);
      }
    }
  });

  test('rejects contradictory image and world results and opposing shoulder/hip axes', () {
    final replay = _Replay(Exercise.squat);
    final profile = _body(Exercise.squat, 85);
    final front = _body(Exercise.squat, 0);
    expect(replay.show(profile, frames: 7).view, PlacementView.side);
    for (final conflict in [
      (image: front.image, world: profile.world),
      (image: profile.image, world: front.world),
      _body(Exercise.squat, 75, hipsBearing: -75),
    ]) {
      final rightAway = replay.show(conflict);
      expect(rightAway.blockAssessment, isTrue);
      final reading = replay.show(conflict, frames: 10);
      expect(reading.view, PlacementView.unknown);
      expect(reading.estimatedDegrees, isNull);
    }
    expect(replay.show(profile).blockAssessment, isTrue);
    expect(replay.show(profile, frames: 7).blockAssessment, isFalse);
  });

  test('qualitative 2D fallback withholds a number and never approves a broad frontal view', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = _Replay(exercise);
      final profile = _body(exercise, 87);
      final reduced = replay.show(profile, frames: 9, useWorld: false);
      expect(reduced.view, PlacementView.side);
      expect(reduced.estimatedDegrees, isNull);
      expect(reduced.blockAssessment, isFalse);
      final front = replay.show(_body(exercise, 5), frames: 9, useWorld: false);
      expect(front.view, PlacementView.moveToSide);
      expect(front.blockAssessment, isTrue);
      expect(front.estimatedDegrees, isNull);
    }
  });

  test('occluded far landmarks withhold yaw and allow observed one-sided reps after recovery', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = _Replay(exercise);
      final side = _body(exercise, 85, farSideVisible: false);
      expect(
        replay.show(_body(exercise, 0), frames: 8).blockAssessment,
        isTrue,
      );
      expect(replay.show(side).blockAssessment, isTrue);
      final settled = replay.show(side, frames: 12);
      expect(settled.view, PlacementView.unknown);
      expect(settled.estimatedDegrees, isNull);
      expect(settled.blockAssessment, isFalse);
      if (exercise == Exercise.pushUp) {
        side.image[23] = const Joint(.5, .5, .1);
        final partial = replay.show(side, frames: 8);
        expect(partial.estimatedDegrees, isNull);
        expect(partial.blockAssessment, isFalse);
      }
    }
  });

  test('rolling camera angle and jitter withhold unstable numbers and use a side-view exit margin', () {
    final replay = _Replay(Exercise.squat);
    expect(
      replay.show(_body(Exercise.squat, 75), frames: 9).view,
      PlacementView.side,
    );
    final edge = replay.show(_body(Exercise.squat, 68));
    expect(edge.blockAssessment, isFalse);
    expect(edge.view, PlacementView.side);
    final drift = replay.show(_body(Exercise.squat, 45));
    expect(drift.blockAssessment, isTrue);
    expect(drift.estimatedDegrees, isNull);
    for (var index = 0; index < 10; index++) {
      final reading = replay.show(
        _body(Exercise.squat, index.isEven ? 15 : 45),
      );
      expect(reading.blockAssessment, isTrue);
      expect(reading.estimatedDegrees, isNull);
    }
  });

  test(
    'maintains a corroborated side view while the torso bends and depth shifts',
    () {
      final replay = _Replay(Exercise.squat);
      final profile = _body(Exercise.squat, 82);
      final lessDepth = _body(Exercise.squat, 61);
      final uncertain = replay.show((
        image: profile.image,
        world: lessDepth.world,
      ), frames: 8);
      expect(uncertain.view, PlacementView.side);
      expect(uncertain.estimatedDegrees, isNull);
      expect(uncertain.blockAssessment, isFalse);

      // Both shoulder and hip axes project vertically as the person crouches.
      final pitch = 32 * math.pi / 180;
      final pitched = [
        for (final joint in profile.world)
          WorldJoint(
            joint.x,
            joint.y + math.sin(pitch) * joint.z,
            math.cos(pitch) * joint.z,
            joint.confidence,
          ),
      ];
      final bent = replay.show((
        image: profile.image,
        world: pitched,
      ), frames: 8);
      expect(bent.view, PlacementView.side);
      expect(bent.estimatedDegrees, greaterThanOrEqualTo(75));
      expect(bent.blockAssessment, isFalse);
      expect(replay.show(_body(Exercise.squat, 55)).blockAssessment, isTrue);
    },
  );

  test(
    'an incomplete initial chain and a single strong frontal axis cannot arm',
    () {
      final replay = _Replay(Exercise.squat);
      final partial = _body(Exercise.squat, 85, farSideVisible: false);
      partial.image[27] = const Joint(0, 0, 0);
      expect(replay.show(partial, frames: 9).blockAssessment, isTrue);
      final front = _body(Exercise.squat, 5);
      front.image[12] = const Joint(0, 0, 0);
      final frontalHip = replay.show(front, frames: 9);
      expect(frontalHip.blockAssessment, isTrue);
      expect(frontalHip.estimatedDegrees, isNull);
      expect(
        replay.show(_body(Exercise.squat, 85), frames: 9).blockAssessment,
        isFalse,
      );
    },
  );

  test('removes readings on loss, multiple bodies, malformed data, time gaps and explicit reset', () {
    final replay = _Replay(Exercise.squat);
    final side = _body(Exercise.squat, 85);
    expect(replay.show(side, frames: 8).estimatedDegrees, 85);
    for (final people in [
      <List<Joint>>[],
      [side.image, side.image],
      [side.image.sublist(0, 15)],
    ]) {
      replay.time += 80;
      final reading = replay.placement.update(
        PoseSample(replay.time, 1, people),
        side.world,
      );
      expect(reading.estimatedDegrees, isNull);
      expect(reading.blockAssessment, isTrue);
      expect(replay.show(side).estimatedDegrees, isNull);
      expect(replay.show(side, frames: 8).estimatedDegrees, 85);
    }
    expect(replay.show(side, step: 900).estimatedDegrees, isNull);
    expect(replay.show(side, frames: 8).estimatedDegrees, 85);
    expect(
      replay.placement
          .update(PoseSample(replay.time - 10, 1, [side.image]), side.world)
          .estimatedDegrees,
      isNull,
    );
    replay.placement.reset();
    expect(replay.show(side).estimatedDegrees, isNull);
    for (final index in [11, 12, 23, 24]) {
      side.world[index] = const WorldJoint(double.nan, 0, 0);
    }
    final invalid = replay.show(side, frames: 8);
    expect(invalid.estimatedDegrees, isNull);
    expect(invalid.view, PlacementView.side);
  });

  test('a standing setup cannot confirm a push-up camera, and a plank cannot confirm a squat view', () {
    final plank = _body(Exercise.pushUp, 88);
    final standing = _body(Exercise.squat, 88);
    for (final (exercise, pose) in [
      (Exercise.pushUp, standing),
      (Exercise.squat, plank),
    ]) {
      final replay = _Replay(exercise);
      final reading = replay.show(pose, frames: 10);
      expect(reading.view, PlacementView.unknown);
      expect(reading.estimatedDegrees, isNull);
    }
  });
}
