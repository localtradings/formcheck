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
  Replay(this.exercise) : analyzer = RepAnalyzer(exercise);
  final Exercise exercise;
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

  void _step(List<List<Joint>> people) {
    time += 75;
    final result = analyzer.accept(PoseSample(time, 1, people));
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
