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
}

class Replay {
  Replay(this.exercise, {this.aspect = 1}) : analyzer = RepAnalyzer(exercise);
  final Exercise exercise;
  final double aspect;
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

  void _step(List<List<Joint>> people) {
    time += 75;
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
