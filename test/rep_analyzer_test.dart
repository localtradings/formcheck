import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/domain/workout.dart';

void main() {
  test('distinguishes a complete shallow squat from a passed squat', () {
    final replay = Replay(Exercise.squat);
    replay.hold(175, 8);
    expect(replay.status, TrackingStatus.ready);
    replay.rep(90);
    replay.rep(116);
    expect(replay.results.map((rep) => rep.outcome), [
      RepOutcome.passed,
      RepOutcome.needsCorrection,
    ]);
    expect(replay.results.last.cue, Cue.squatDepth);
  });

  test('does not count an interrupted or noisy partial movement', () {
    final replay = Replay(Exercise.squat);
    replay.hold(175, 8);
    replay.hold(148, 4);
    replay.hold(175, 8);
    replay.hold(90, 4);
    replay.noPose();
    replay.hold(175, 8);
    expect(replay.results, isEmpty);
    replay.rep(90);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test('pauses when a second person is detected', () {
    final replay = Replay(Exercise.squat);
    replay.hold(175, 8);
    replay.hold(91, 5);
    replay.noPose(secondPerson: true);
    expect(replay.status, TrackingStatus.reposition);
    replay.hold(175, 8);
    expect(replay.results, isEmpty);
  });

  test('keeps the camera steady during an early bend before a full rep is established', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      replay.hold(175, 9);
      replay.hold(142, 5);
      expect(replay.status, TrackingStatus.moving);
      replay.hold(175, 9);
      expect(replay.results, isEmpty);
      expect(replay.status, TrackingStatus.ready);
    }
  });

  test('counts a complete shallow rep when the two limb segments fold around a planted support', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise, frameMs: 50);
      final squat = exercise == Exercise.squat;
      List<Joint> centered(double degrees) {
        final pose = List.filled(33, const Joint(0, 0, 0));
        final halfAngle = degrees * math.pi / 360;
        final segment = squat ? .18 : .14;
        final contact = squat
            ? const Joint(.5, .8, .98)
            : const Joint(.68, .74, .98);
        final first = squat ? 23 : 11;
        final body = Joint(
          contact.x,
          contact.y - 2 * segment * math.sin(halfAngle),
          .98,
        );
        pose[first] = body;
        pose[first + 2] = Joint(
          contact.x + segment * math.cos(halfAngle),
          (body.y + contact.y) / 2,
          .98,
        );
        pose[first + 4] = contact;
        if (squat) {
          pose[11] = Joint(body.x, body.y - .2, .98);
        } else {
          pose[27] = const Joint(.18, .58, .98);
          pose[23] = Joint((.18 + body.x) / 2, (.58 + body.y) / 2, .98);
        }
        return pose;
      }

      for (final top in [156.0, 170.0]) {
        replay.show(centered(top), 15);
        for (var step = 1; step <= 48; step++) {
          final degrees =
              top - (top - 125) * (1 - math.cos(math.pi * step / 24)) / 2;
          replay.show(centered(degrees), 1);
        }
        replay.show(centered(top), 10);
      }
      expect(replay.results, hasLength(2), reason: exercise.name);
      expect(
        replay.results.map((rep) => rep.outcome),
        everyElement(RepOutcome.needsCorrection),
      );
    }
  });

  test('acquires the side with the visible joints needed to start', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      List<Joint> pose(double angle) =>
          replay.bothSides(angle)
            ..[exercise == Exercise.squat ? 11 : 23] = const Joint(0, 0, 0);

      replay.show(pose(175), 8);
      expect(replay.status, TrackingStatus.ready, reason: exercise.name);
      replay.show(pose(90), 7);
      replay.show(pose(175), 8);
      expect(replay.results.single.outcome, RepOutcome.passed);
    }
  });

  test('reconsiders a confident side that never reaches a valid start', () {
    final replay = Replay(Exercise.pushUp);
    const bentWrist = Joint(.80, .60, .98);
    replay.show(replay._pose(175)..[15] = bentWrist, 8);
    expect(replay.status, TrackingStatus.getReady);

    final both = replay.bothSides(175)..[15] = bentWrist;
    replay.show(both, 2);
    expect(replay.status, TrackingStatus.getReady);
    replay.show(both, 6);
    expect(replay.status, TrackingStatus.ready);
    replay.show(replay.bothSides(90), 7);
    replay.show(both, 8);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test('holds the chosen side throughout a descent and return', () {
    final replay = Replay(Exercise.squat);
    replay.show(replay.bothSides(175), 8);
    final bottom = replay.bothSides(90, left: .76, right: .99);
    final farHip = bottom[24];
    bottom[26] = Joint(farHip.x, farHip.y + .08, .99);
    bottom[28] = Joint(farHip.x, farHip.y + .20, .99);
    replay.show(bottom, 7);
    expect(replay.status, TrackingStatus.moving);
    replay.show(replay.bothSides(175), 8);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test(
    'can re-arm on a valid side when only the selected knee or elbow has bent',
    () {
      for (final exercise in [Exercise.squat, Exercise.pushUp]) {
        final replay = Replay(exercise);
        replay.show(replay.bothSides(175), 9);
        final start = replay.bothSides(175);
        final index = exercise == Exercise.squat ? 25 : 13;
        start[index] = Joint(start[index].x - .15, start[index].y, .98);
        replay.show(start, 1);
        expect(replay.analyzer.measuredSide, 0);
        replay.show(start, 14);
        expect(replay.analyzer.measuredSide, 1, reason: exercise.name);
        expect(replay.status, TrackingStatus.ready);
        final bent = replay.bothSides(90);
        replay.show(bent, 7);
        replay.show(start, 9);
        expect(replay.results.single.outcome, RepOutcome.passed);
      }
    },
  );

  test('losing the tracked knee cannot finish a rep on the other leg', () {
    final replay = Replay(Exercise.squat);
    replay.show(replay.bothSides(175), 8);
    replay.show(replay.bothSides(90), 7);
    final lost = replay.bothSides(90)..[25] = const Joint(0, 0, 0);
    replay.show(lost, 1);
    expect(replay.status, TrackingStatus.reposition);
    final newTop = replay.bothSides(175)..[25] = const Joint(0, 0, 0);
    replay.show(newTop, 8);
    expect(replay.results, isEmpty);
    expect(replay.status, TrackingStatus.ready);
    replay.show(lost, 7);
    replay.show(newTop, 8);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test('a single-frame subject jump cannot close an unfinished rep', () {
    for (final aspect in [.75, 1.6]) {
      final replay = Replay(Exercise.squat, aspect: aspect);
      replay.hold(175, 8);
      replay.hold(90, 7);
      expect(replay.status, TrackingStatus.moving);

      final dx = aspect < 1 ? .32 : .17;
      List<Joint> shifted(double angle) => [
        for (final point in replay._pose(angle))
          Joint(point.x + dx, point.y, point.visibility),
      ];

      replay.show(shifted(175), 1);
      expect(
        replay.status,
        TrackingStatus.reposition,
        reason: 'aspect $aspect',
      );
      replay.show(shifted(175), 3);
      expect(replay.status, TrackingStatus.getReady);
      replay.show(shifted(175), 6);
      expect(replay.status, TrackingStatus.ready);
      expect(replay.results, isEmpty);
      replay.show(shifted(90), 7);
      replay.show(shifted(175), 8);
      expect(replay.results.single.outcome, RepOutcome.passed);
    }
  });

  test('a push-up with an obscured hip still detects a subject change', () {
    final replay = Replay(Exercise.pushUp);
    replay.hold(175, 8);
    replay.hold(90, 7, missingHip: true);
    expect(replay.status, TrackingStatus.moving);
    final moved = [
      for (final point in replay._pose(90, missingHip: true))
        Joint(point.x + .28, point.y, point.visibility),
    ];
    replay.show(moved, 1);
    expect(replay.status, TrackingStatus.reposition);
    replay.hold(175, 8);
    expect(replay.results, isEmpty);
    expect(replay.status, TrackingStatus.ready);
  });

  test('a long frame gap discards a descent and requires a fresh top hold', () {
    final replay = Replay(Exercise.squat);
    replay.hold(175, 8);
    replay.hold(90, 7);
    replay.time += RepAnalyzer.maxFrameGapMs;
    replay.hold(175, 3);
    expect(replay.status, TrackingStatus.getReady);
    replay.hold(175, 5);
    expect(replay.status, TrackingStatus.ready);
    expect(replay.results, isEmpty);
    replay.rep(90);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test(
    'push-ups report both hip drift and insufficient alignment evidence',
    () {
      final replay = Replay(Exercise.pushUp);
      replay.hold(175, 8);
      replay.rep(90);
      replay.rep(89, drift: true);
      replay.rep(88, missingHip: true);
      expect(replay.results.map((rep) => rep.outcome), [
        RepOutcome.passed,
        RepOutcome.needsCorrection,
        RepOutcome.unassessed,
      ]);
      expect(replay.results[1].cue, Cue.bodyLine);
      expect(replay.results[2].cue, Cue.reframe);
    },
  );

  test('joint bending or lifting the foot or hand without lowering the body never counts', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      final start = replay._pose(175), bent = replay._pose(90);
      final body = exercise == Exercise.squat ? 23 : 11;
      final middle = body + 2;
      final middleOnly = List.of(start);
      middleOnly[middle] = Joint(start[middle].x - .18, start[middle].y, .98);
      final shifted = replay.shift(bent, dy: start[body].y - bent[body].y);
      for (final falseBottom in [
        middleOnly,
        shifted,
        replay.shift(middleOnly, dy: .08),
      ]) {
        replay.show(start, 9);
        replay.show(falseBottom, 7);
        replay.show(start, 9);
        expect(replay.results, isEmpty, reason: exercise.name);
      }
      replay.rep(90);
      expect(replay.results.single.outcome, RepOutcome.passed);
    }
  });

  test('requires a valid ending posture after the leg or arm straightens', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      replay.hold(175, 9);
      replay.hold(90, 7);
      final invalid = replay._pose(175, drift: exercise == Exercise.pushUp);
      if (exercise == Exercise.squat) {
        invalid[11] = Joint(invalid[23].x, invalid[23].y + .14, .98);
      }
      replay.show(invalid, 12);
      expect(replay.results, isEmpty, reason: exercise.name);
      replay.hold(175, 9);
      expect(replay.results, isEmpty);
      replay.rep(90);
      expect(replay.results.single.outcome, RepOutcome.passed);
    }
  });

  test(
    'a lone implausibly deep sample cannot turn a shallow rep into a pass',
    () {
      for (final exercise in [Exercise.squat, Exercise.pushUp]) {
        final replay = Replay(exercise);
        replay.hold(175, 9);
        replay.hold(118, 6);
        replay.hold(55, 1);
        replay.hold(118, 6);
        replay.hold(175, 9);
        expect(replay.results, hasLength(1));
        expect(
          replay.results.single.outcome,
          RepOutcome.unassessed,
          reason: exercise.name,
        );
        expect(replay.results.single.cue, Cue.depthUnclear);
        expect(replay.results.single.bottomAngleDegrees, isNull);
      }
    },
  );

  test('separated noisy hip observations cannot add up to a sustained alignment fault', () {
    final replay = Replay(Exercise.pushUp);
    replay.hold(175, 9);
    for (var pulse = 0; pulse < 5; pulse++) {
      replay.hold(90, 2);
      replay.hold(90, 1, drift: true);
    }
    replay.hold(175, 9);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test('checks visible hip drift on the approach to push-up depth', () {
    final replay = Replay(Exercise.pushUp);
    replay.hold(175, 9);
    replay.hold(138, 8, drift: true);
    replay.hold(85, 9);
    replay.hold(175, 9);
    expect(replay.results.single.outcome, RepOutcome.needsCorrection);
    expect(replay.results.single.cue, Cue.bodyLine);
  });

  test('a visibly folded leg cannot arm a standard push-up from a straight hip line', () {
    final replay = Replay(Exercise.pushUp);
    final top = replay._pose(175);
    final hip = top[23], ankle = top[27];
    top[25] = Joint((hip.x + ankle.x) / 2, (hip.y + ankle.y) / 2 + .14, .95);
    replay.show(top, 12);
    expect(replay.status, TrackingStatus.getReady);
    replay.hold(90, 7);
    replay.show(top, 10);
    expect(replay.results, isEmpty);
    replay.hold(175, 9);
    replay.rep(90);
    expect(replay.results.single.outcome, RepOutcome.passed);
  });

  test('tolerates small camera drift and abandons an active rep if its support slides away', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      List<Joint> shifted(double angle, double dx, double dy) => [
        for (final point in replay._pose(angle))
          Joint(point.x + dx, point.y + dy, point.visibility),
      ];
      replay.hold(175, 9);
      replay.show(shifted(90, .016, .007), 8);
      replay.show(shifted(175, .015, .006), 9);
      expect(replay.results.single.outcome, RepOutcome.passed);
      replay.show(shifted(90, .016, .007), 8);
      replay.show(shifted(92, .16, .006), 1);
      expect(replay.status, TrackingStatus.reposition, reason: exercise.name);
      replay.hold(175, 10);
      expect(replay.results, hasLength(1));
    }
  });

  test('push-up hip-line readings close to the target stay unassessed', () {
    final replay = Replay(Exercise.pushUp);
    replay.hold(175, 9);
    for (final line in [147.0, 154.0, 156.0, 161.0]) {
      final bottom = replay._pose(90);
      final shoulder = bottom[11], ankle = bottom[27];
      final bend = .5 / math.tan(line * math.pi / 360);
      bottom[23] = Joint(
        (shoulder.x + ankle.x) / 2 - (ankle.y - shoulder.y) * bend,
        (shoulder.y + ankle.y) / 2 + (ankle.x - shoulder.x) * bend,
        .98,
      );
      replay.show(bottom, 9);
      replay.hold(175, 9);
    }
    expect(replay.results.map((rep) => rep.outcome), [
      RepOutcome.needsCorrection,
      RepOutcome.unassessed,
      RepOutcome.unassessed,
      RepOutcome.passed,
    ]);
    expect(replay.results[1].bottomAngleDegrees, 90);
    expect(replay.results[1].cue, Cue.alignmentUnclear);
  });

  test(
    'each borderline target reports the supported bottom angle and uncertainty',
    () {
      for (final exercise in [Exercise.squat, Exercise.pushUp]) {
        final replay = Replay(exercise);
        final target = replay.analyzer.profile.depth;
        replay.hold(175, 9);
        for (final depth in [target - 2, target + 2]) {
          replay.rep(depth);
          final result = replay.results.last;
          expect(result.outcome, RepOutcome.unassessed);
          expect(result.cue, Cue.depthUnclear);
          expect(result.bottomAngleDegrees, depth.round());
        }
      }
    },
  );

  test('a missing interval across the bottom cannot turn a possible deep rep into a shallow fault', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      replay.hold(175, 9);
      replay.hold(118, 7);
      replay.time += 170;
      replay.hold(118, 6);
      replay.hold(175, 9);
      expect(replay.results.single.outcome, RepOutcome.unassessed);
      expect(replay.results.single.bottomAngleDegrees, isNull);
      expect(replay.results.single.cue, Cue.depthUnclear);
    }
  });

  test('extension still below the starting height cannot close a rep', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      final replay = Replay(exercise);
      final top = replay._pose(175);
      final contact = top[exercise == Exercise.squat ? 27 : 15];
      final compressed = [
        for (final joint in top)
          Joint(
            joint.x,
            contact.y + (joint.y - contact.y) * .70,
            joint.visibility,
          ),
      ];
      replay.show(top, 9);
      replay.hold(90, 7);
      replay.show(compressed, 12);
      replay.show(top, 9);
      expect(replay.results, isEmpty, reason: exercise.name);
      replay.rep(90);
      expect(replay.results.single.outcome, RepOutcome.passed);
    }
  });

  test('a completed elbow and shoulder cycle with the hip hidden at the finish is unassessed', () {
    final replay = Replay(Exercise.pushUp);
    replay.hold(175, 9);
    replay.hold(88, 7);
    replay.hold(175, 12, missingHip: true);
    final result = replay.results.single;
    expect(result.outcome, RepOutcome.unassessed);
    expect(result.cue, Cue.reframe);
    expect(result.bottomAngleDegrees, 88);
    expect(replay.status, TrackingStatus.reposition);
    replay.hold(175, 9);
    replay.rep(90);
    expect(replay.results.last.outcome, RepOutcome.passed);
  });

  test('measured side and live angle are cleared with tracking loss and explicit reset', () {
    final replay = Replay(Exercise.squat);
    expect(replay.analyzer.jointAngleDegrees, isNull);
    expect(replay.analyzer.measuredSide, isNull);
    replay.hold(175, 9);
    expect(replay.analyzer.jointAngleDegrees, closeTo(175, .01));
    expect(replay.analyzer.measuredSide, 0);
    replay.noPose(secondPerson: true);
    expect(replay.analyzer.jointAngleDegrees, isNull);
    expect(replay.analyzer.measuredSide, isNull);
    replay.hold(175, 9);
    replay.analyzer.reset();
    expect(replay.analyzer.jointAngleDegrees, isNull);
    expect(replay.analyzer.measuredSide, isNull);
  });

  test('continuous fast and slow side-view movements agree across capture rates, framing and reflection', () {
    for (final exercise in [Exercise.squat, Exercise.pushUp]) {
      for (final frameMs in [33, 67, 100, 150]) {
        for (final (aspect, scale, mirror) in [
          (0.75, .8, true),
          (1.6, 1.12, false),
        ]) {
          final replay = Replay(exercise, aspect: aspect, frameMs: frameMs);
          List<Joint> pose(double angle) => [
            for (final point in replay._pose(angle))
              Joint(
                .5 + (point.x - .5) * (mirror ? -scale : scale) / aspect,
                .5 + (point.y - .5) * scale,
                point.visibility,
              ),
          ];
          replay.show(pose(175), (600 / frameMs).ceil());
          for (final (bottom, halfCycleMs) in [(83.0, 850), (118.0, 1350)]) {
            final steps = (halfCycleMs / frameMs).ceil();
            for (var step = 1; step <= 2 * steps; step++) {
              final bend = (1 - math.cos(math.pi * step / steps)) / 2;
              replay.show(pose(175 - bend * (175 - bottom)), 1);
            }
            replay.show(pose(175), (450 / frameMs).ceil());
          }
          final condition = '${exercise.name}, ${frameMs}ms, aspect $aspect';
          expect(replay.results.map((rep) => rep.outcome), [
            RepOutcome.passed,
            RepOutcome.needsCorrection,
          ], reason: condition);
          expect(
            replay.results.first.bottomAngleDegrees,
            inInclusiveRange(83, 91),
            reason: condition,
          );
          expect(
            replay.results.last.bottomAngleDegrees,
            inInclusiveRange(118, 121),
            reason: condition,
          );
        }
      }
    }
  });
}

class Replay {
  Replay(this.exercise, {this.aspect = 1, this.frameMs = 75})
    : analyzer = RepAnalyzer(exercise);
  final Exercise exercise;
  final double aspect;
  final int frameMs;
  final RepAnalyzer analyzer;
  final results = <RepResult>[];
  int time = 0;
  TrackingStatus status = TrackingStatus.getReady;

  void rep(double depth, {bool drift = false, bool missingHip = false}) {
    hold(depth, 7, drift: drift, missingHip: missingHip);
    hold(175, 8);
  }

  void noPose({bool secondPerson = false}) =>
      _step(secondPerson ? [_pose(175), _pose(175)] : []);

  void hold(
    double angle,
    int frames, {
    bool drift = false,
    bool missingHip = false,
  }) {
    for (var i = 0; i < frames; i++) {
      _step([_pose(angle, drift: drift, missingHip: missingHip)]);
    }
  }

  List<Joint> bothSides(double angle, {double left = .98, double right = .82}) {
    final joints = _pose(angle);
    for (final index in [11, 13, 15, 23, 25, 27]) {
      final point = joints[index];
      if (!point.visible) continue;
      joints[index] = Joint(point.x, point.y, left);
      joints[index + 1] = Joint(point.x + .01, point.y, right);
    }
    return joints;
  }

  void show(List<Joint> joints, int frames) {
    for (var frame = 0; frame < frames; frame++) {
      _step([joints]);
    }
  }

  List<Joint> shift(List<Joint> joints, {required double dy}) => [
    for (final point in joints) Joint(point.x, point.y + dy, point.visibility),
  ];

  void _step(List<List<Joint>> people) {
    time += frameMs;
    final result = analyzer.accept(PoseSample(time, aspect, people));
    status = result.status;
    if (result.rep != null) results.add(result.rep!);
  }

  List<Joint> _pose(
    double angle, {
    bool drift = false,
    bool missingHip = false,
  }) {
    final points = List.filled(33, const Joint(0, 0, 0));
    final theta = angle * math.pi / 180;
    if (exercise == Exercise.squat) {
      final hip = Joint(
        0.55 - math.sin(theta) * 0.18,
        0.62 + math.cos(theta) * 0.18,
        0.98,
      );
      points[11] = Joint(hip.x + 0.03, hip.y - 0.2, 0.98);
      points[23] = hip;
      points[25] = const Joint(0.55, 0.62, 0.98);
      points[27] = const Joint(0.55, 0.8, 0.98);
    } else {
      final shoulder = Joint(
        0.65 - math.sin(theta) * 0.15,
        0.60 + math.cos(theta) * 0.15,
        0.98,
      );
      points[11] = shoulder;
      points[13] = const Joint(0.65, 0.60, 0.98);
      points[15] = const Joint(0.65, 0.74, 0.98);
      points[23] = Joint(
        (shoulder.x + 0.16) / 2,
        (shoulder.y + 0.60) / 2 + (drift ? 0.18 : 0),
        missingHip ? 0.3 : 0.98,
      );
      points[27] = const Joint(0.16, 0.60, 0.98);
    }
    return points;
  }
}
